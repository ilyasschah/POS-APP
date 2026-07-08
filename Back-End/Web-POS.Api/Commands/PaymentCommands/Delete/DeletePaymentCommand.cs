using FluentValidation;
using MediatR;
using Api.Services;

namespace Api.Commands.PaymentCommands.Delete
{
    public class DeletePaymentCommand : IRequest<bool>
    {
        public int Id { get; set; }
        public int CompanyId { get; set; }

        public DeletePaymentCommand(int id, int companyId)
        {
            Id = id;
            CompanyId = companyId;
        }

        public class DeletePaymentCommandHandler : IRequestHandler<DeletePaymentCommand, bool>
        {
            private readonly PaymentService _service;

            public DeletePaymentCommandHandler(PaymentService service)
            {
                _service = service;
            }

            public async Task<bool> Handle(DeletePaymentCommand request, CancellationToken cancellationToken)
            {
                return await _service.Delete(request.Id, request.CompanyId);
            }
        }

        public class DeletePaymentCommandValidator : AbstractValidator<DeletePaymentCommand>
        {
            public DeletePaymentCommandValidator()
            {
                RuleFor(c => c.Id).GreaterThan(0);
                RuleFor(c => c.CompanyId).GreaterThan(0);
            }
        }
    }
}