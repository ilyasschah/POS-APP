using FluentValidation;
using MediatR;
using Api.Helpers;
using Api.Models;
using Api.Services;

namespace Api.Commands.VoidReasonCommads.Add
{
    public class AddVoidReasonCommand : IRequest<VoidReasonDto>
    {
        public CreateVoidReasonRequest Request { get; }

        public AddVoidReasonCommand(CreateVoidReasonRequest request)
        {
            Request = request;
        }

        public class AddVoidReasonCommandHandler : IRequestHandler<AddVoidReasonCommand, VoidReasonDto>
        {
            private readonly VoidReasonService _service;

            public AddVoidReasonCommandHandler(VoidReasonService service)
            {
                _service = service;
            }

            public async Task<VoidReasonDto> Handle(AddVoidReasonCommand command, CancellationToken cancellationToken)
            {
                var newEntity = await _service.Create(command.Request);
                return MapperVoidReason.MapToVoidReasonDto(newEntity);
            }
        }

        public class AddVoidReasonCommandValidator : AbstractValidator<AddVoidReasonCommand>
        {
            public AddVoidReasonCommandValidator()
            {
                RuleFor(c => c.Request.Name).NotEmpty();
                RuleFor(c => c.Request.Rank).GreaterThanOrEqualTo(0);
            }
        }
    }
}