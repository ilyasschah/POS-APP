using FluentValidation;
using MediatR;
using Api.Services;
using Api.Models;

namespace Api.Commands.PaymentCommands.Update
{
    public class UpdatePaymentCommand : IRequest<PaymentDto>
    {
        public UpdatePaymentRequest Request { get; set; }
        public int CompanyId { get; set; }

        public UpdatePaymentCommand(UpdatePaymentRequest request, int companyId)
        {
            Request = request;
            CompanyId = companyId;
        }

        public class UpdatePaymentCommandHandler : IRequestHandler<UpdatePaymentCommand, PaymentDto>
        {
            private readonly PaymentService _service;

            public UpdatePaymentCommandHandler(PaymentService service)
            {
                _service = service;
            }

            public async Task<PaymentDto> Handle(UpdatePaymentCommand request, CancellationToken cancellationToken)
            {
                return await _service.Update(request.Request, request.CompanyId);
            }
        }

        public class UpdatePaymentCommandValidator : AbstractValidator<UpdatePaymentCommand>
        {
            public UpdatePaymentCommandValidator()
            {
                RuleFor(c => c.Request.Id).GreaterThan(0);
                RuleFor(c => c.Request.Amount).GreaterThanOrEqualTo(0);
                RuleFor(c => c.Request.Date).NotEmpty();
                RuleFor(c => c.CompanyId).GreaterThan(0);
            }
        }
    }
}