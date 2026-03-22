using FluentValidation;
using MediatR;
using Api.Services;

namespace Api.Commands.PaymentTypeCommands.Delete
{
    public class DeletePaymentTypeCommand : IRequest<bool>
    {
        public int Id { get; }
        public int CompanyId { get; }

        public DeletePaymentTypeCommand(int id, int companyId)
        {
            Id = id;
            CompanyId = companyId;
        }

        public class DeletePaymentTypeCommandHandler : IRequestHandler<DeletePaymentTypeCommand, bool>
        {
            private readonly PaymentTypeService _service;

            public DeletePaymentTypeCommandHandler(PaymentTypeService service)
            {
                _service = service;
            }

            public Task<bool> Handle(DeletePaymentTypeCommand request, CancellationToken cancellationToken)
            {
                return _service.DeleteAsync(request.Id, request.CompanyId);
            }
        }
        public class DeletePaymentTypeCommandValidator : AbstractValidator<DeletePaymentTypeCommand>
        {
            public DeletePaymentTypeCommandValidator()
            {
                RuleFor(c => c.Id).GreaterThan(0).WithMessage("Id must be valid.");
                RuleFor(c => c.CompanyId).GreaterThan(0).WithMessage("CompanyId must be valid.");
            }
    }  }
}