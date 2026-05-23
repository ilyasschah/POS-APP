using FluentValidation;
using MediatR;
using Api.DataBase;
using Api.Models;
using Api.Services;
using Microsoft.EntityFrameworkCore;

namespace Api.Commands.DocumentsCommands.Update
{
    public class UpdateDocumentCommand : IRequest<bool>
    {
        public UpdateDocumentRequest Request { get; }
        public int CompanyId { get; }

        public UpdateDocumentCommand(UpdateDocumentRequest request, int companyId)
        {
            Request = request;
            CompanyId = companyId;
        }

        public class UpdateDocumentCommandHandler : IRequestHandler<UpdateDocumentCommand, bool>
        {
            private readonly DocumentService _service;
            private readonly AppDbContext    _db;

            public UpdateDocumentCommandHandler(DocumentService service, AppDbContext db)
            {
                _service = service;
                _db      = db;
            }

            public async Task<bool> Handle(UpdateDocumentCommand command, CancellationToken cancellationToken)
            {
                // Rule 3: marking a document as Unpaid (0) must wipe its payment
                // records so the database stays financially consistent.
                if (command.Request.PaidStatus == 0)
                {
                    var payments = await _db.Payments
                        .Where(p => p.DocumentId == command.Request.Id
                                 && p.CompanyId  == command.CompanyId)
                        .ToListAsync(cancellationToken);

                    if (payments.Count > 0)
                    {
                        _db.Payments.RemoveRange(payments);
                        await _db.SaveChangesAsync(cancellationToken);
                    }
                }

                return await _service.UpdateAsync(command.Request, command.CompanyId);
            }
        }

        public class UpdateDocumentCommandValidator : AbstractValidator<UpdateDocumentCommand>
        {
            public UpdateDocumentCommandValidator()
            {
                RuleFor(c => c.CompanyId)
                    .GreaterThan(0).WithMessage("Company ID must be valid.");

                RuleFor(c => c.Request.Id)
                    .GreaterThan(0).WithMessage("Document ID is required to perform an update.");

                RuleFor(c => c.Request.Number)
                    .NotEmpty().WithMessage("Document Number cannot be empty if provided.")
                    .When(c => c.Request.Number != null);

                RuleFor(c => c.Request.Total)
                    .GreaterThanOrEqualTo(0).WithMessage("Total cannot be negative.")
                    .When(c => c.Request.Total.HasValue);
            }
        }
    }
}