using FluentValidation;
using MediatR;
using Api.Services;

namespace Api.Commands.BarcodeCommands.Delete
{
    public class DeleteBarcodeByIdCommand : IRequest<bool>
    {
        public int Id { get; set; }
        public int CompanyId { get; set; }

        public DeleteBarcodeByIdCommand(int id, int companyId)
        {
            Id = id;
            CompanyId = companyId;
        }

        public class DeleteBarcodeByIdCommandHandler : IRequestHandler<DeleteBarcodeByIdCommand, bool>
        {
            private readonly BarcodeService _service;

            public DeleteBarcodeByIdCommandHandler(BarcodeService service)
            {
                _service = service;
            }

            public async Task<bool> Handle(DeleteBarcodeByIdCommand request, CancellationToken cancellationToken)
            {
                return await _service.Delete(request.Id, request.CompanyId);
            }
        }

        public class DeleteBarcodeByIdCommandValidator : AbstractValidator<DeleteBarcodeByIdCommand>
        {
            public DeleteBarcodeByIdCommandValidator()
            {
                RuleFor(c => c.Id).GreaterThan(0);
                RuleFor(c => c.CompanyId).GreaterThan(0);
            }
        }
    }
}